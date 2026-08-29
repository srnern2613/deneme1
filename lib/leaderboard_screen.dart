// ============================================================================
// DOSYA ADI: lib/leaderboard_screen.dart
// AÇIKLAMA: Faz 4 - Kusursuz İkon Konumlandırma, Sıfır Sıkışma & Lig Arenası
// GÖREVLER & GÜVENLİK ÖNLEMLERİ:
//   1. Ödül Rozetleri Üst Satıra Taşındı: İlerleme çubuğu tam genişliğe kavuştu.
//   2. İkon & Kutu Optimizasyonu: 44x44 kutu içinde optik merkezli 22px ikonlar.
//   3. Sağ Aksiyon Alanı Genişletildi: Kilit ve "AL" butonları standart touch-target boyutuna çekildi.
//   4. Çift Tıklama & Asenkron Çökme Koruması: _claimingChallengeIds + mounted kontrolü.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'xp_shop_service.dart';
import 'celebration_dialog.dart';

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
  final List<Map<String, dynamic>> _challenges = [
    {
      'id': 'c1',
      'title': 'Günün Kelime Avcısı',
      'desc': 'Kitap okurken 3 yeni kelime avla',
      'current': 3,
      'target': 3,
      'rewardXp': 30,
      'rewardGems': 2,
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
      'rewardXp': 50,
      'rewardGems': 5,
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
      'rewardXp': 40,
      'rewardGems': 3,
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

  /// Kullanıcı XP'sini çeker ve sıralamayı oluşturur
  Future<void> _loadLeagueData() async {
    try {
      final xp = await XpShopService.instance.getTotalXp();
      final userCurrentXp = xp > 0 ? xp : 4108;

      final List<Map<String, dynamic>> simulatedLeague = [
        {'name': 'Zeynep K.', 'xp': userCurrentXp + 30, 'avatar': '👑', 'isUser': false},
        {'name': 'Eren (Sen)', 'xp': userCurrentXp, 'avatar': '🛡️', 'isUser': true},
        {'name': 'Mert Demir', 'xp': (userCurrentXp - 10).clamp(0, 999999), 'avatar': '⚡', 'isUser': false},
        {'name': 'Canan Yılmaz', 'xp': (userCurrentXp - 55).clamp(0, 999999), 'avatar': '🦊', 'isUser': false},
        {'name': 'Burak Kaya', 'xp': (userCurrentXp - 90).clamp(0, 999999), 'avatar': '🎯', 'isUser': false},
        {'name': 'Ayşe S.', 'xp': (userCurrentXp - 130).clamp(0, 999999), 'avatar': '🌸', 'isUser': false},
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
    final int gems = challenge['rewardGems'] as int;
    final String title = challenge['title'] as String;

    await XpShopService.instance.addXp(xp).catchError((_) => 0);
    await XpShopService.instance.addGems(gems).catchError((_) => 0);

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
      earnedGems: gems,
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

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070B14),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Lig Arenası & Görevler',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- 1. LİG BAŞLIK & SIRALAMA BİLGİ KARTI ---
                    _buildLeagueHeaderCard(userRank, xpGapToNext, rivalName),
                    const SizedBox(height: 20),

                    // --- 2. GÜNLÜK MİKRO-MEYDAN OKUMALAR ---
                    Text(
                      'Mikro-Meydan Okumalar',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    ..._challenges.map((c) => _buildChallengeCard(c)),
                    const SizedBox(height: 22),

                    // --- 3. LİDERLİK TABLOSU ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            '12. Arena Sıralaması',
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'İlk 3 Üst Lige Çıkar',
                            style: GoogleFonts.outfit(color: const Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildLeaderboardList(),
                  ],
                ),
              ),
            ),
    );
  }

  /// Üst Lig Özeti Kartı (Optik Hizalı ve Taşma Korumalı)
  Widget _buildLeagueHeaderCard(int userRank, int xpGap, String rivalName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
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

  /// Mikro Görev Kartı (Görsel Dengesizlik ve Sıkışma Tamamen Giderildi)
  Widget _buildChallengeCard(Map<String, dynamic> challenge) {
    final String cId = challenge['id'] as String;
    final int current = challenge['current'] as int;
    final int target = challenge['target'] as int;
    final bool isCompleted = current >= target;
    final bool isClaimed = challenge['isClaimed'] as bool;
    final Color itemColor = challenge['color'] as Color;
    final double progress = (current / target).clamp(0.0, 1.0);
    final bool isProcessing = _claimingChallengeIds.contains(cId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted && !isClaimed 
              ? itemColor.withValues(alpha: 0.6) 
              : const Color(0xFF1F2937),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Sol İkon Kutusu (Optik Dengeli)
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: itemColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Icon(challenge['icon'] as IconData, color: itemColor, size: 22),
            ),
          ),
          const SizedBox(width: 12),

          // 2. Orta Bölüm: Başlık, Ödül Rozetleri ve Tam Genişlikte İlerleme Çubuğu
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Satır: Görev Başlığı ve Sağında XP & Elmas Rozetleri
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        challenge['title'] as String,
                        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                          ),
                          child: Row(
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
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(PhosphorIcons.diamondBold, color: Color(0xFF38BDF8), size: 10),
                              const SizedBox(width: 2),
                              Text(
                                '+${challenge['rewardGems']}',
                                style: GoogleFonts.outfit(color: const Color(0xFF38BDF8), fontWeight: FontWeight.w900, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 3),

                // 2. Satır: Görev Açıklaması
                Text(
                  challenge['desc'] as String,
                  style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // 3. Satır: Tam Genişlikte İlerleme Çubuğu ve Sayacı
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: const Color(0xFF1E293B),
                          valueColor: AlwaysStoppedAnimation<Color>(itemColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$current/$target',
                      style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // 3. Sağ Aksiyon Bölümü (Sabit Genişlik: 58px)
          SizedBox(
            width: 58,
            child: isCompleted && !isClaimed
                ? SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      onPressed: isProcessing ? null : () => _claimReward(challenge),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: itemColor,
                        foregroundColor: const Color(0xFF0F172A),
                        padding: EdgeInsets.zero,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isProcessing
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)))
                          : Text('AL', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12.5)),
                    ),
                  )
                : isClaimed
                    ? const Center(
                        child: Icon(PhosphorIcons.checkCircleFill, color: Color(0xFF10B981), size: 26),
                      )
                    : const Center(
                        child: Icon(PhosphorIcons.lockSimpleBold, color: Color(0xFF475569), size: 22),
                      ),
          ),
        ],
      ),
    );
  }

  /// Liderlik Tablosu (Genişlik & Taşma Korumalı)
  Widget _buildLeaderboardList() {
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

        Color rankColor = const Color(0xFF94A3B8);
        if (rank == 1) rankColor = const Color(0xFFF59E0B);
        if (rank == 2) rankColor = const Color(0xFFE2E8F0);
        if (rank == 3) rankColor = const Color(0xFFD97706);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isUser 
                ? const Color(0xFF4F46E5).withValues(alpha: 0.25) 
                : const Color(0xFF111827).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isUser 
                  ? const Color(0xFF6366F1) 
                  : (rank <= 3 ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFF1F2937)),
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
                    color: Colors.white,
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
                  color: isUser ? const Color(0xFFFDE68A) : const Color(0xFF94A3B8),
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