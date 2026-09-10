// ============================================================================
// DOSYA ADI: lib/app_header.dart
// AÇIKLAMA: Reaktif, Taşma Korumalı (Overflow-Proof), Dinamik Sayaç Listesine
//            Sahip ve Canlı Notifier Dinleyebilen Global Üst Bar.
//
// GÜNCELLEME: Tüm ikonlar (elmasla tutarlı olacak şekilde) PhosphorIcons'a
// taşındı — artık hiçbiri ham Unicode emoji değil, bu yüzden platformdan
// platforma boy/hizalama tutarsızlığı yaşanmıyor. Sağdaki sayaçlar sabit
// kod tekrarı yerine _HeaderStat listesiyle render ediliyor: yeni bir sayaç
// türü eklemek listeye bir eleman eklemekten ibaret. "Selam" ikonu artık
// AppHeader'a gömülü değil — mevcut `leading` slotu üzerinden çağıran sayfa
// tarafından veriliyor, böylece diğer sayfalar kendi leading widget'larını
// (geri butonu, avatar, menü vb.) özgürce kullanabilir.
// ============================================================================

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'xp_shop_service.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final String? badgeEmoji;
  // NOT: Bu iki alan "başlangıç değeri, sonra reaktif güncellenir" DEĞİLDİR.
  // Verildiğinde ilgili pill TAMAMEN STATİK gösterilir ve canlı XpShopService
  // notifier'ına ABONE OLMAZ (ör. başka bir oyuncunun profil önizlemesi için).
  // Kendi oyuncusunun canlı elmas/XP'sini gösterecek ekranlar bunları null
  // bırakmalı; aksi halde sayaç asla güncellenmez.
  final int? initialGems;
  final int? initialXp;
  final int? streak;
  final VoidCallback? onShopTap;
  final VoidCallback? onStreakTap;
  final Widget? leading;
  final bool showStats;

  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.badgeEmoji,
    this.initialGems,
    this.initialXp,
    this.streak,
    this.onShopTap,
    this.onStreakTap,
    this.leading,
    this.showStats = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(74);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Header sabit yükseklikli (preferredSize) olduğundan, sistem font ölçeği
    // (erişilebilirlik/Large Text) sınırsız büyüyebilirse hem başlık/alt
    // başlık dikeyde hem de sağdaki pill'ler yatayda taşabilir. Ölçeği makul
    // bir üst sınırla (1.15x) kelepçeliyoruz.
    final clampedScaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.15);

    // Sağdaki sayaç listesi — DİNAMİK: yeni bir sayaç türü eklemek için
    // build() içindeki tek işiniz bu listeye bir _HeaderStat eklemek.
    final stats = <_HeaderStat>[
      if (streak != null)
        _HeaderStat(
          icon: PhosphorIcons.fireBold,
          accentColor: Colors.deepOrange,
          bgColor: Colors.orange.withValues(alpha: isDark ? 0.16 : 0.12),
          borderColor: Colors.orange.withValues(alpha: 0.35),
          flex: 1,
          staticValue: streak,
          onTap: onStreakTap,
        ),
      _HeaderStat(
        icon: PhosphorIcons.diamondBold,
        accentColor: isDark ? Colors.cyanAccent : Colors.cyan[700]!,
        bgColor: Colors.cyan.withValues(alpha: isDark ? 0.16 : 0.12),
        borderColor: Colors.cyan.withValues(alpha: 0.35),
        flex: 2,
        onTap: onShopTap,
        staticValue: initialGems,
        liveValue: initialGems == null ? XpShopService.instance.gemsNotifier : null,
      ),
      _HeaderStat(
        icon: PhosphorIcons.lightningBold,
        accentColor: isDark ? Colors.amberAccent : Colors.amber[800]!,
        bgColor: Colors.amber.withValues(alpha: isDark ? 0.16 : 0.12),
        borderColor: Colors.amber.withValues(alpha: 0.35),
        flex: 2,
        staticValue: initialXp,
        liveValue: initialXp == null ? XpShopService.instance.xpNotifier : null,
      ),
    ];

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: clampedScaler),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF090D16) : const Color(0xFFF6F8FC),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF6366F1).withValues(alpha: 0.14),
                    const Color(0xFF090D16).withValues(alpha: 0.95),
                  ]
                : [
                    const Color(0xFF818CF8).withValues(alpha: 0.10),
                    const Color(0xFFF6F8FC),
                  ],
          ),
          border: Border(
            bottom: BorderSide(
              color: isDark
                  ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                  : const Color(0xFFE2E8F0).withValues(alpha: 0.8),
              width: 1,
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Sayaç bölgesine, gerçek ihtiyacından fazlasını vermemek için
              // üst sınır: mevcut genişliğin en fazla %42'si. Kısa sayılar
              // başlığı sıkıştırmaz; bu sınır yalnızca rakamlar gerçekten
              // çok büyüdüğünde devreye girer.
              final maxStatsWidth = constraints.maxWidth * 0.42;

              return Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 8),
                  ],
                  // SOL TARAF: Başlık ve Alt Başlık — sayaçların ihtiyaç
                  // duyduğu genişlik düşüldükten sonra kalan TÜM alanı alır.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.6,
                                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (badgeEmoji != null) ...[
                              const SizedBox(width: 6),
                              Text(badgeEmoji!, style: const TextStyle(fontSize: 18)),
                            ],
                          ],
                        ),
                        // subtitle artık tamamen opsiyonel: bu ekranda
                        // "Bugün seni bekleyen görevler..." satırını kaldırmak
                        // için çağıran taraf sadece `subtitle` parametresini
                        // geçmemeli (aşağıdaki not'a bakın). Başka bir sayfa
                        // ileride bir açıklama satırı isterse, bu widget onu
                        // hâlâ destekliyor.
                        if (subtitle != null) ...[
                          const SizedBox(height: 1),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              letterSpacing: 0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),

                  // SAĞ TARAF: Sayaçlar — sabit flex yerine doğal genişliğini
                  // alır (IntrinsicWidth); yalnızca rakamlar gerçekten devasa
                  // büyürse ConstrainedBox üst sınırı devreye girip her pill
                  // içindeki FittedBox ile orantılı küçülme başlar.
                  if (showStats && stats.isNotEmpty)
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxStatsWidth),
                      child: IntrinsicWidth(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            for (var i = 0; i < stats.length; i++) ...[
                              if (i > 0) const SizedBox(width: 4),
                              Flexible(flex: stats[i].flex, child: stats[i].build()),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Sağ üstteki tek bir sayaç pill'inin görsel + veri tanımı. AppHeader'ın
/// "dinamik" olmasının temeli budur: yeni bir sayaç türü eklemek, build()
/// içindeki listeye bir eleman eklemekten ibarettir — kod tekrarı yok.
class _HeaderStat {
  final IconData icon;
  final Color accentColor;
  final Color bgColor;
  final Color borderColor;
  final int flex;
  final VoidCallback? onTap;
  final int? staticValue; // null ise [liveValue] kullanılır (reaktif mod).
  final ValueListenable<int>? liveValue;

  const _HeaderStat({
    required this.icon,
    required this.accentColor,
    required this.bgColor,
    required this.borderColor,
    this.flex = 2,
    this.onTap,
    this.staticValue,
    this.liveValue,
  }) : assert(
          staticValue != null || liveValue != null,
          '_HeaderStat: staticValue ya da liveValue değerlerinden biri verilmeli.',
        );

  Widget build() {
    if (staticValue != null) return _pill(staticValue!);
    return ValueListenableBuilder<int>(
      valueListenable: liveValue!,
      builder: (context, value, _) => _pill(value),
    );
  }

  Widget _pill(int value) => _StatPill(
        icon: icon,
        value: value,
        color: accentColor,
        bgColor: bgColor,
        borderColor: borderColor,
        onTap: onTap,
      );
}

/// Tek bir sayaç pill'i. İkon her zaman PhosphorIcons (vektör) — platforma
/// göre boyutu/hizalaması değişen renkli emoji glifleri yerine her zaman
/// aynı boyutta ve tutarlı çizgi kalınlığında render olur.
class _StatPill extends StatelessWidget {
  final IconData icon;
  final int value;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback? onTap;

  const _StatPill({
    required this.icon,
    required this.value,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap != null
          ? () {
              HapticFeedback.selectionClick();
              onTap!();
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1),
        ),
        // Bir bütün olarak, gereken alandan dar bir yere sıkışırsa (devasa
        // sayı + dar ekran) RenderFlex overflow yerine orantılı küçülür.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 3),
              Text(
                '$value',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  color: color,
                  letterSpacing: 0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}