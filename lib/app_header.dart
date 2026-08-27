// ============================================================================
// DOSYA ADI: lib/app_header.dart
// AÇIKLAMA: Mor/İndigo Işıltılı (Ambient Glow), Cam Efektli & Çift Tema Uyumlu Üst Bar
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final String? badgeEmoji;
  final int gems;
  final int xp;
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
    this.gems = 0,
    this.xp = 0,
    this.streak,
    this.onShopTap,
    this.onStreakTap,
    this.leading,
    this.showStats = true,
  });

  // Standart App Bar yüksekliği
  @override
  Size get preferredSize => const Size.fromHeight(74);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF090D16) : const Color(0xFFF6F8FC),
        // Mor / İndigo Ortam Işıltısı (Ambient Glow)
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF6366F1).withValues(alpha: 0.14), // Karanlık mod yumuşak indigo ışıltısı
                  const Color(0xFF090D16).withValues(alpha: 0.95),
                ]
              : [
                  const Color(0xFF818CF8).withValues(alpha: 0.10), // Aydınlık mod lavanta ışıltısı
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
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 8),
            ],
            // ----------------------------------------------------------------
            // ÇÖZÜLEN SORUN (RenderFlex Overflow / Yazı Taşması):
            // Başlık çok uzun olduğunda veya rozet emojisi eklendiğinde sağdaki
            // elmas ve XP sayaçları ekrandan taşıp sarı-siyah hata şeridi veriyordu.
            // Çözüm: Başlık alanı 'Expanded' + 'Flexible' ve 'ellipsis' ile sarıldı.
            // ----------------------------------------------------------------
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
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badgeEmoji != null) ...[
                        const SizedBox(width: 6),
                        Text(badgeEmoji!, style: const TextStyle(fontSize: 18)),
                      ],
                    ],
                  ),
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
            const SizedBox(width: 8),

            // Sağ Taraf Sayaç Kapsülleri (Cam Efektli & Canlı Renkli)
            if (showStats)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (streak != null) ...[
                    _buildStatPill(
                      emoji: '🔥',
                      value: '$streak',
                      color: Colors.deepOrange,
                      bgColor: Colors.orange.withValues(alpha: isDark ? 0.16 : 0.12),
                      borderColor: Colors.orange.withValues(alpha: 0.35),
                      onTap: onStreakTap,
                    ),
                    const SizedBox(width: 6),
                  ],
                  _buildStatPill(
                    emoji: '💎',
                    value: '$gems',
                    color: isDark ? Colors.cyanAccent : Colors.cyan[700]!,
                    bgColor: Colors.cyan.withValues(alpha: isDark ? 0.16 : 0.12),
                    borderColor: Colors.cyan.withValues(alpha: 0.35),
                    onTap: onShopTap,
                  ),
                  const SizedBox(width: 6),
                  _buildStatPill(
                    emoji: '⚡',
                    value: '$xp',
                    color: isDark ? Colors.amberAccent : Colors.amber[800]!,
                    bgColor: Colors.amber.withValues(alpha: isDark ? 0.16 : 0.12),
                    borderColor: Colors.amber.withValues(alpha: 0.35),
                    onTap: null,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill({
    required String emoji,
    required String value,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap != null
          ? () {
              HapticFeedback.selectionClick();
              onTap();
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.5, vertical: 5.5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 3.5),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 11.5,
                color: color,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}