// ============================================================================
// DOSYA ADI: lib/leaderboard_screen.dart
// AÇIKLAMA: Faz 4 - Kusursuz İkon Konumlandırma, Sıfır Sıkışma & Lig Arenası
// GÖREVLER & GÜVENLİK ÖNLEMLERİ:
//   1. Ödül Rozetleri Üst Satıra Taşındı: İlerleme çubuğu tam genişliğe kavuştu.
//   2. İkon & Kutu Optimizasyonu: 44x44 kutu içinde optik merkezli 22px ikonlar.
//   3. Sağ Aksiyon Alanı Genişletildi: Kilit ve "AL" butonları standart touch-target boyutuna çekildi.
//   4. Çift Tıklama & Asenkron Çökme Koruması: _claimingChallengeIds + mounted kontrolü.
// ============================================================================

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'core/theme/draconic_theme.dart';
import 'xp_shop_service.dart';
import 'celebration_dialog.dart';
import 'core/design_system/primitives.dart'; // ScreenHeaderBadge & RuneTitle

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _userXp = 0;
  bool _isLoading = true;

  // Çift tıklama ile mükerrer ödül alımını engelleyen güvenlik seti
  final Set<String> _claimingChallengeIds = {};

  // Liderlik tablosu simülasyon listesi
  List<Map<String, dynamic>> _leaderboardData = [];

  // Günlük ve Haftalık Mikro-Meydan Okumalar
  // EJDERHA ROTASI V2 — FAZ 1: Elmas ödülü kaldırıldı, eski 'rewardGems'
  // değerleri sabit bir oranla (1 elmas = 10 XP) 'rewardXp'ye katıldı.
  final List<Map<String, dynamic>> _challenges = [
    {
      'id': 'c1',
      'title': 'Günün Kelime Avcısı',
      'desc': 'Kitap okurken 3 yeni kelime avla',
      'current': 3,
      'target': 3,
      'rewardXp': 50, // eski: 30 XP + 2 elmas
      'isClaimed': false,
      'icon': PhosphorIcons.crosshairBold,
      'color': const Color(0xFF10B981),
    },
    {
      'id': 'c2',
      'title': 'Hafıza Şampiyonu',
      'desc': '5 SRS kart tekrarını hatasız tamamla',
      'current': 5,
      'target': 5,
      'rewardXp': 100, // eski: 50 XP + 5 elmas
      'isClaimed': false,
      'icon': PhosphorIcons.brainBold,
      'color': const Color(0xFF818CF8),
    },
    {
      'id': 'c3',
      'title': 'Odaklı Okuma Seansı',
      'desc': 'Bugün en az 10 sayfa kitap oku',
      'current': 6,
      'target': 10,
      'rewardXp': 70, // eski: 40 XP + 3 elmas
      'isClaimed': false,
      'icon': PhosphorIcons.bookOpenBold,
      'color': const Color(0xFFF59E0B),
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadLeagueData();
  }

  /// Pazar gecesine kalan süreyi dinamik hesaplar
  String _getRemainingSeasonTime() {
    final now = DateTime.now();
    final int daysUntilSunday = DateTime.sunday - now.weekday;
    final int days = daysUntilSunday >= 0 ? daysUntilSunday : daysUntilSunday + 7;
    final int hours = 23 - now.hour;
    return '$days Gün $hours Saat';
  }

  // P0-5: main.dart'taki IndexedStack bu sekmeyi canlı tuttuğu için Arena'ya
  // her dönüşte veri tazelenmiyordu (Profil'in aynı sınıftaki simulatedLeague
  // kopyasıyla aynı bug) — main.dart artık her sekme geçişinde bunu çağırıyor.
  Future<void> refreshLeagueData() => _loadLeagueData();

  /// Kullanıcı XP'sini çeker ve sıralamayı oluşturur
  Future<void> _loadLeagueData() async {
    try {
      // P0-C: liderlik artık toplam XP'yi değil, gerçekten haftalık sıfırlanan
      // sezon sayacını okuyor — "SEZON XP · haftalık sıfırlanır" etiketi
      // şimdi doğru veriye karşılık geliyor.
      final xp = await XpShopService.instance.getSeasonXp();
      final userCurrentXp = xp;

      final List<Map<String, dynamic>> simulatedLeague = [
        {'name': 'Seydihan Akıl.', 'xp': userCurrentXp + 30, 'avatar': '👑', 'isUser': false},
        {'name': 'Eren (Sen)', 'xp': userCurrentXp, 'avatar': '🛡️', 'isUser': true},
        {'name': 'Sezer', 'xp': (userCurrentXp - 10).clamp(0, 999999), 'avatar': '⚡', 'isUser': false},
        // UI/UX Düzeltme Listesi — P0-6: eski isimler ("Zenci", "Çinli")
        // ırkçı/etnik hakaretti — App Store + Play ret riski, TestFlight/
        // internal test dahil hiçbir build'de görünmemeli. Ignis evreninden
        // tematik isimlerle değiştirildi.
        {'name': 'Alevkanat', 'xp': (userCurrentXp - 55).clamp(0, 999999), 'avatar': '🦊', 'isUser': false},
        {'name': 'Gölgeavcı', 'xp': (userCurrentXp - 90).clamp(0, 999999), 'avatar': '🎯', 'isUser': false},
        {'name': 'Gece.', 'xp': (userCurrentXp - 130).clamp(0, 999999), 'avatar': '🌸', 'isUser': false},
        {'name': 'Deniz Acar', 'xp': (userCurrentXp - 180).clamp(0, 999999), 'avatar': '🚀', 'isUser': false},
        {'name': 'Selin Öztürk', 'xp': (userCurrentXp - 230).clamp(0, 999999), 'avatar': '⭐', 'isUser': false},
        {'name': 'Emre Aydın', 'xp': (userCurrentXp - 280).clamp(0, 999999), 'avatar': '🎮', 'isUser': false},
        {'name': 'Kaan Vural', 'xp': (userCurrentXp - 330).clamp(0, 999999), 'avatar': '🔥', 'isUser': false},
      ];

      _sortLeague(simulatedLeague);

      if (!mounted) return;
      setState(() {
        _userXp = userCurrentXp;
        _leaderboardData = simulatedLeague;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  /// Listeyi XP'ye göre büyükten küçüğe sıralar
  void _sortLeague(List<Map<String, dynamic>> list) {
    list.sort((a, b) => (b['xp'] as int).compareTo(a['xp'] as int));
  }

  /// Tamamlanan görevin ödülünü toplar ve CelebrationDialog ile kutlar
  Future<void> _claimReward(Map<String, dynamic> challenge) async {
    final String cId = challenge['id'] as String;
    if (_claimingChallengeIds.contains(cId) || (challenge['isClaimed'] as bool)) return;

    _claimingChallengeIds.add(cId);
    HapticFeedback.heavyImpact();

    final int xp = challenge['rewardXp'] as int;
    final String title = challenge['title'] as String;

    await XpShopService.instance.addXp(xp).catchError((_) => 0);

    if (!mounted) return;
    setState(() {
      challenge['isClaimed'] = true;
      _userXp += xp;

      // Kullanıcının tablodaki kaydını güncelle ve yeniden sırala
      final userIndex = _leaderboardData.indexWhere((e) => e['isUser'] == true);
      if (userIndex != -1) {
        _leaderboardData[userIndex]['xp'] = _userXp;
        _sortLeague(_leaderboardData);
      }
      _claimingChallengeIds.remove(cId);
    });

    CelebrationDialog.show(
      context,
      emoji: '🎯',
      title: 'Meydan Okuma Tamamlandı!',
      subtitle: '"$title" görevini tamamlayarak ödülleri kasanıza eklediniz.',
      themeColor: const Color(0xFF10B981),
      earnedXp: xp,
      actionLabel: 'Harika!',
    );
  }

  @override
  Widget build(BuildContext context) {
    final int userIndex = _leaderboardData.indexWhere((e) => e['isUser'] == true);
    final int userRank = userIndex != -1 ? userIndex + 1 : 2;

    int xpGapToNext = 0;
    String rivalName = '';
    if (userIndex > 0) {
      final rival = _leaderboardData[userIndex - 1];
      xpGapToNext = ((rival['xp'] as int) - _userXp + 1).clamp(1, 9999);
      rivalName = rival['name'] as String;
    }

    final theme = Theme.of(context).extension<DraconicTheme>()!;
    return Scaffold(
      backgroundColor: theme.background,
      // İlerleme'ye özel atmosferik zemin — diğer sekmelerdeki desenle aynı:
      // tam ekran görsel + aşağıya doğru koyu zemine eriyen gradyan.
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/basarimlar.webp',
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
                    theme.background.withValues(alpha: 0.15),
                    theme.background.withValues(alpha: 0.65),
                    theme.background,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.infoTeal))
          : SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Lobi/Profil'deki gibi nefes alan özel başlık — standart
                    // AppBar sıkışıklığı yerine SafeArea içinde serbest Row.
                    _buildScreenHeaderRow(),
                    const SizedBox(height: 22),

                    // --- 1. LİG BAŞLIK & SIRALAMA BİLGİ KARTI ---
                    _buildLeagueHeaderCard(userRank, xpGapToNext, rivalName),
                    const SizedBox(height: 20),

                    // --- 2. GÜNLÜK MİKRO-MEYDAN OKUMALAR ---
                    // EJDERHA ROTASI V2 — FAZ 5: Arena Odaklılık. Görevler
                    // artık tam genişlikte dikey 3 kart yerine, tek satırlık
                    // yatay kaydırılabilir kompakt kartlar — ekranın büyük
                    // kısmı aşağıdaki liderlik tablosuna ayrılıyor.
                    Text(
                      'Mikro-Meydan Okumalar',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: theme.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    // EJDERHA ROTASI V2 — Faz C: Sabit yükseklikli SizedBox +
                    // Column(Spacer) kombinasyonu, büyük yazı tipi/erişilebilirlik
                    // ölçeklemesinde veya 2 satıra taşan başlıklarda birkaç
                    // piksellik "BOTTOM OVERFLOWED" hatasına yol açıyordu.
                    // Çözüm: dış yüksekliğe güvenlik payı eklendi VE kart
                    // içeriği kendi SingleChildScrollView'ı içine alındı — bu
                    // sayede içerik ne kadar büyürse büyüsün taşma render
                    // hatası artık YAPISAL olarak imkansız (en kötü ihtimalle
                    // kart içinde görünmez bir iç kaydırma payı oluşur).
                    SizedBox(
                      height: 148,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _challenges.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 10),
                        itemBuilder: (context, index) => _buildChallengeCard(_challenges[index]),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // --- 3. LİDERLİK TABLOSU ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            // Ertelenen tasarım kararı: "Arena" kelimesi
                            // buradan kaldırıldı — o isim zaten pratik/dövüş
                            // sekmesine ait; burada tekrar kullanmak "Arena"
                            // ile "Sıralama" ekranlarının aynı yer sanılması
                            // sorununu geri getiriyordu.
                            '12. Lig Sıralaması',
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: theme.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.successEmerald.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'İlk 3 Üst Lige Çıkar',
                            style: GoogleFonts.outfit(color: const Color(0xFF6EE7B7), fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // P0-4: header'daki XP pill'i her sekmede TOPLAM XP gösteriyor
                    // (bkz. XpShopService.instance.xpNotifier); bu listedeki sayılar
                    // ise sezonluk/lig XP'si — aynı ekranda iki farklı XP sayısı yan
                    // yana durunca "XP'm gitti" izlenimi veriyordu. Karar: header
                    // toplam XP'de sabit kalıyor, burası açıkça "Sezon XP" etiketleniyor.
                    Text(
                      'SEZON XP · haftalık sıfırlanır',
                      style: GoogleFonts.outfit(color: theme.textMuted, fontWeight: FontWeight.w700, fontSize: 10.5, letterSpacing: 0.3),
                    ),
                    const SizedBox(height: 8),
                    _buildLeaderboardList(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Lobi/Profil'de kurulan referans başlık: sol avatar/geri alanı yok (bu
  // ekrana zaten Navigator ile girilir, Profil de aynı şekilde geri butonu
  // göstermiyor — tutarlılık), Lora serif başlık + sağda AYNI ikon/renk
  // eşleşmeli (Işık=XP mavi, Sketch-logo=Elmas yeşil) canlı rozetler.
  Widget _buildScreenHeaderRow() {
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    return Row(
      children: [
        ScreenHeaderBadge(icon: PhosphorIcons.trophyBold, color: theme.primaryAmber),
        const SizedBox(width: 12),
        // N-5: alt bar sekmesi artık "Arena" (Karar #8) ve o sekmenin ekran
        // başlığı da "Arena" — bu ekranın başlığında aynı kelime geçince
        // ikisi aynı yer sanılıyordu. "Sıralama" olarak ayrıştırıldı.
        const Expanded(
          child: RuneTitle(title: 'Sıralama', subtitle: 'Günlük Görevler & Lig'),
        ),
        _buildHeaderStatPill(icon: PhosphorIcons.lightningBold, color: theme.infoTeal, listenable: XpShopService.instance.xpNotifier),
      ],
    );
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

  /// Üst Lig Özeti Kartı — EJDERHA ROTASI V2 Faz A "Ignis Temizliği":
  /// maskot ve konuşma balonu kaldırıldı, sade Apple tarzı bir özet kart.
  Widget _buildLeagueHeaderCard(int userRank, int xpGap, String rivalName) {
    return Container(
      width: double.infinity,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(PhosphorIcons.trophyBold, color: Color(0xFFF59E0B), size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '12. Arena: Kelime Ustası',
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sezon Bitişi: ${_getRemainingSeasonTime()}',
                      style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                ),
                child: Text(
                  '#$userRank. Sıra',
                  style: GoogleFonts.outfit(color: const Color(0xFFFDE68A), fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
            ],
          ),
          if (xpGap > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF111827).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(PhosphorIcons.lightningBold, color: Color(0xFF38BDF8), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${userRank - 1}. sıradaki $rivalName adlı rakibini geçmek için son $xpGap XP!',
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Kompakt Yatay Görev Kartı — EJDERHA ROTASI V2 FAZ 5: sabit 148px
  /// genişlikte, yalnızca XP ödülüne odaklı, ikon üstte / ilerleme altta.
  Widget _buildChallengeCard(Map<String, dynamic> challenge) {
    final String cId = challenge['id'] as String;
    final int current = challenge['current'] as int;
    final int target = challenge['target'] as int;
    final bool isCompleted = current >= target;
    final bool isClaimed = challenge['isClaimed'] as bool;
    final Color itemColor = challenge['color'] as Color;
    final double progress = (current / target).clamp(0.0, 1.0);
    final bool isProcessing = _claimingChallengeIds.contains(cId);
    final theme = Theme.of(context).extension<DraconicTheme>()!;

    // Kart artık sabit yüksekliğini DIŞ SizedBox'tan (148) alıyor; kendi
    // içinde `mainAxisSize: MainAxisSize.min` + `SingleChildScrollView` ile
    // sarılı — bu iki katmanlı güvence, içeriğin (2 satırlık başlık, büyük
    // yazı tipi ölçeklemesi vb. yüzünden) ayrılan alanı birkaç piksel aşması
    // durumunda bile artık render hatası (`OVERFLOWED BY n PIXELS`) DEĞİL,
    // en fazla görünmez bir iç kaydırma üretir. `Spacer()` da bu yüzden sabit
    // bir SizedBox boşluğuyla değiştirildi (esnek boşluk, sınırsız yükseklikli
    // bir scroll view içinde anlamsız/undefined davranışa yol açar).
    return Container(
      width: 148,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.surfaceDark.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCompleted && !isClaimed
              ? itemColor.withValues(alpha: 0.6)
              : theme.borderSubtle,
          width: isCompleted && !isClaimed ? 1.5 : 1,
        ),
      ),
      child: SingleChildScrollView(
        // Dikey eksende varsayılan (kaydırılabilir) physics bilinçli olarak
        // korunuyor: normal şartlarda 148px'e rahatça sığar ve kaydırma
        // hissedilmez, ama aşırı büyük erişilebilirlik yazı tipi gibi uç bir
        // durumda içerik taşarsa kullanıcı hâlâ kaydırıp görebilir — sessizce
        // kırpılmaz.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: itemColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(challenge['icon'] as IconData, color: itemColor, size: 17),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(PhosphorIcons.lightningBold, color: Colors.orange, size: 10),
                      const SizedBox(width: 2),
                      Text(
                        '+${challenge['rewardXp']}',
                        style: GoogleFonts.outfit(color: Colors.orange, fontWeight: FontWeight.w900, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              challenge['title'] as String,
              style: GoogleFonts.outfit(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: theme.borderSubtle,
                valueColor: AlwaysStoppedAnimation<Color>(itemColor),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 26,
              child: isCompleted && !isClaimed
                  ? ElevatedButton(
                      onPressed: isProcessing ? null : () => _claimReward(challenge),
                      style: ElevatedButton.styleFrom(
                        // C-1: "AL" butonu her kartın kendi rengini (itemColor)
                        // taşıyordu — yan yana 3 farklı dolu renk, 3 farklı
                        // buton TÜRÜ sanılmasına yol açıyordu. Vurgu renkten
                        // değil dolgudan geliyor: tüm birincil aksiyonlar tek
                        // bir görünüme (amber) sahip olmalı.
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: theme.surfaceDark,
                        padding: EdgeInsets.zero,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: isProcessing
                          ? SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: theme.surfaceDark))
                          : Text('AL', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11.5)),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isClaimed ? PhosphorIcons.checkCircleFill : PhosphorIcons.lockSimpleBold,
                          color: isClaimed ? const Color(0xFF10B981) : const Color(0xFF475569),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$current/$target',
                          style: GoogleFonts.outfit(color: theme.textSecondary, fontWeight: FontWeight.bold, fontSize: 10.5),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Liderlik Tablosu (Genişlik & Taşma Korumalı)
  Widget _buildLeaderboardList() {
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _leaderboardData.length,
      separatorBuilder: (context, index) {
        if (index == 2) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Expanded(child: Divider(color: Color(0xFF10B981), thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '▲ YÜKSELME HATTI ▲',
                    style: GoogleFonts.outfit(color: const Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                ),
                const Expanded(child: Divider(color: Color(0xFF10B981), thickness: 1)),
              ],
            ),
          );
        }
        if (index == 6) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Expanded(child: Divider(color: Color(0xFFEF4444), thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '▼ DÜŞME HATTI ▼',
                    style: GoogleFonts.outfit(color: const Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                ),
                const Expanded(child: Divider(color: Color(0xFFEF4444), thickness: 1)),
              ],
            ),
          );
        }
        return const SizedBox(height: 8);
      },
      itemBuilder: (context, index) {
        final item = _leaderboardData[index];
        final int rank = index + 1;
        final bool isUser = item['isUser'] as bool;

        Color rankColor = theme.textSecondary;
        if (rank == 1) rankColor = const Color(0xFFF59E0B);
        if (rank == 2) rankColor = const Color(0xFFE2E8F0);
        if (rank == 3) rankColor = const Color(0xFFD97706);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            // C-2: indigo bu uygulamada hafıza/bilişsel alan rengi — "bu
            // satır sensin" anlamı taşımıyor. "Sen" vurgusu amber'e (eylem/
            // birincil vurgu rengi) taşındı.
            color: isUser
                ? const Color(0xFFF59E0B).withValues(alpha: 0.18)
                : theme.surfaceLight.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isUser
                  ? const Color(0xFFF59E0B)
                  : (rank <= 3 ? const Color(0xFF10B981).withValues(alpha: 0.3) : theme.borderSubtle),
              width: isUser ? 1.8 : 1.2,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '$rank',
                  style: GoogleFonts.outfit(
                    color: rankColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 10),
              Text(item['avatar'] as String, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item['name'] as String,
                  style: GoogleFonts.outfit(
                    color: theme.textPrimary,
                    fontWeight: isUser ? FontWeight.w900 : FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${item['xp']} XP',
                style: GoogleFonts.outfit(
                  color: isUser ? const Color(0xFFFDE68A) : theme.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}